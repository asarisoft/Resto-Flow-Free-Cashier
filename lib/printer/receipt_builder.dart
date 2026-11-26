import 'dart:io';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import '../models/transaction.dart' as models;
import '../models/resto_profile.dart';
import '../models/transaction_item.dart';
import '../models/shift.dart';
import '../features/shifts/shift_calc.dart';
import '../features/settings/logo_image_service.dart';

class ReceiptBuilder {
  static final _fmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Teks struk untuk dibagikan (mis. ke WhatsApp). Isinya sama dengan
  /// [buildText]; dibungkus ``` agar WhatsApp menampilkannya monospace
  /// (kolom rata). Aplikasi lain menampilkan penandanya apa adanya.
  static String shareText(models.Transaction txn, RestoProfile profile) =>
      '```\n${buildText(txn, profile).trimRight()}\n```';

  /// Bytes lengkap untuk printer: logo raster hitam-putih (bila diset) di atas
  /// header, lalu teks struk. Logo hilang/rusak/gagal decode → cetak tanpa
  /// logo (tidak pernah gagal cetak).
  static Future<List<int>> buildReceipt(
      models.Transaction txn, RestoProfile profile) async {
    final bytes = <int>[];
    final logo = await _logoRasterBytes(profile);
    if (logo != null) bytes.addAll(logo);
    bytes.addAll(nameHeaderBytes(profile));
    bytes.addAll(buildText(txn, profile, withName: false).codeUnits);
    return bytes;
  }

  /// Nama toko rata tengah, ukuran ganda (GS ! 0x11) + tebal (ESC E 1).
  /// Huruf 2x lebar → bungkus di setengah kolom kertas.
  static List<int> nameHeaderBytes(RestoProfile profile) {
    final w = (profile.paperWidth == 80 ? 48 : 32) ~/ 2;
    final lines = wrap(profile.name.toUpperCase(), w).join('\n');
    return [
      0x1B, 0x61, 0x01, 0x1D, 0x21, 0x11, 0x1B, 0x45, 0x01,
      ...'$lines\n'.codeUnits,
      0x1D, 0x21, 0x00, 0x1B, 0x45, 0x00, 0x1B, 0x61, 0x00,
    ];
  }

  static Future<CapabilityProfile>? _profileFuture;

  /// Raster logo ESC/POS (GS v 0) hitam-putih, lebar ±60% kertas, rata tengah.
  /// Returns null bila logo tidak diset / hilang / rusak / gagal decode.
  static Future<List<int>?> _logoRasterBytes(RestoProfile profile) async {
    final path = profile.logoPath;
    if (!profile.useLogo || path == null || path.isEmpty) return null;
    try {
      final abs = await LogoImageService.resolvePath(path);
      final file = File(abs);
      if (!await file.exists()) return null;
      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded == null) return null;

      // Ratakan ke latar putih: piksel transparan (hitam + alpha 0) kalau
      // langsung diraster jadi kotak hitam.
      final flattened = LogoImageService.flattenToWhite(decoded);

      // ±60% lebar kertas: 58mm ≈ 384 dot, 80mm ≈ 576 dot.
      final targetWidth = profile.paperWidth == 80 ? 346 : 230;
      final resized = img.copyResize(flattened, width: targetWidth);

      final gen = Generator(
        profile.paperWidth == 80 ? PaperSize.mm80 : PaperSize.mm58,
        await (_profileFuture ??= CapabilityProfile.load()),
      );
      final raster = gen.imageRaster(resized, align: PosAlign.center);
      // Kembalikan alignment ke kiri + pindah baris sebelum teks struk.
      return [...raster, 0x1B, 0x61, 0x00, 0x0A];
    } catch (_) {
      return null;
    }
  }

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

  /// [withName] false: nama toko dicetak terpisah (besar) oleh [nameHeaderBytes].
  static String buildText(models.Transaction txn, RestoProfile profile,
      {bool withName = true}) {
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

    if (withName) center(profile.name.toUpperCase());
    if (profile.address != null && profile.address!.isNotEmpty) {
      center(profile.address!);
    }
    if (profile.phone != null && profile.phone!.isNotEmpty) {
      center('Telp ${profile.phone}');
    }
    buf.writeln();
    divider();

    final dateStr = DateFormat('dd/MM/yy HH:mm').format(txn.createdAt);
    line('No: ${txn.number == null ? '-' : '#${txn.number}'}', dateStr);
    divider();
    if (txn.isVoid) {
      center('*** DIBATALKAN ***');
      if (txn.voidReason != null && txn.voidReason!.isNotEmpty) {
        center(txn.voidReason!);
      }
      divider();
    }

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
      line(txn.discountLabel, '-${_fmt.format(txn.discount)}');
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

  /// Rekap tutup kasir (teks sama untuk printer & preview).
  static String buildShiftRecapText({
    required RestoProfile profile,
    required Shift shift,
    required ShiftRecap recap,
  }) {
    final buf = StringBuffer();
    final w = profile.paperWidth == 80 ? 48 : 32;
    final df = DateFormat('dd/MM/yy HH:mm');

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
    center('REKAP KASIR');
    divider();
    line('Buka', df.format(shift.openedAt));
    line('Tutup', df.format(shift.closedAt ?? DateTime.now()));
    line('Oleh', '${shift.openedBy} → ${shift.closedBy ?? '-'}');
    divider();
    line('Omzet Tunai', _fmt.format(recap.cashRevenue));
    line('Omzet QRIS', _fmt.format(recap.qrisRevenue));
    line('Omzet Kartu', _fmt.format(recap.cardRevenue));
    if (recap.otherRevenue != 0) {
      line('Omzet Lain', _fmt.format(recap.otherRevenue));
    }
    line('Pengeluaran', _fmt.format(recap.totalExpense));
    divider();
    line('Modal awal', _fmt.format(shift.openingCash));
    line('Omzet tunai', _fmt.format(recap.cashRevenue));
    line('Pengeluaran', '-${_fmt.format(recap.totalExpense)}');
    line('Kas seharusnya', _fmt.format(recap.expectedCash));
    line('Kas di laci', _fmt.format(shift.countedCash ?? 0));
    line('Selisih', _fmt.format(recap.difference));
    divider();

    if (profile.footerNote != null && profile.footerNote!.isNotEmpty) {
      center(profile.footerNote!);
    }
    buf.writeln();
    buf.writeln();
    buf.writeln();

    return buf.toString();
  }
}
