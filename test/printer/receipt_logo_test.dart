import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kasir_resto/models/resto_profile.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';
import 'package:kasir_resto/printer/receipt_builder.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

/// Perintah raster logo (GS v 0).
const gsV0 = [0x1D, 0x76, 0x30];

RestoProfile _profile({bool useLogo = false, String? logoPath}) => RestoProfile(
      name: 'Warung Budi',
      useLogo: useLogo,
      logoPath: logoPath,
      createdAt: DateTime(2026),
    );

final _txn = Transaction(
  number: 1,
  items: const [
    TransactionItem(productId: 'a', name: 'Nasi Goreng', price: 10000, hpp: 4000, qty: 1),
  ],
  subtotal: 10000,
  total: 10000,
  paid: 10000,
  change: 0,
  profit: 6000,
  createdAt: DateTime(2026),
);

bool _containsSub(List<int> haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('kasir_logo_test_');
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
  });

  tearDown(() async {
    if (await docs.exists()) await docs.delete(recursive: true);
  });

  Future<void> writeLogo() async {
    final dir = Directory(p.join(docs.path, 'images', 'logo'));
    await dir.create(recursive: true);
    final logo = img.Image(100, 50);
    img.fill(logo, 0xFF000000);
    final file = File(p.join(dir.path, 'logo.jpg'));
    await file.writeAsBytes(img.encodePng(logo));
  }

  test('buildReceipt prepends GS v 0 raster when logo is set', () async {
    await writeLogo();

    final bytes = await ReceiptBuilder.buildReceipt(
        _txn, _profile(useLogo: true, logoPath: 'logo/logo.jpg'));

    expect(_containsSub(bytes, gsV0), isTrue,
        reason: 'logo harus dicetak sebagai raster GS v 0');
    expect(String.fromCharCodes(bytes), contains('TOTAL'));
  });

  test('buildReceipt hanya byte ASCII, garis pakai "-"', () async {
    final bytes = await ReceiptBuilder.buildReceipt(_txn, _profile());
    expect(bytes.every((b) => b >= 0 && b <= 0x7F), isTrue,
        reason: 'karakter Unicode (mis. ─) tercetak kosong di printer');
    expect(String.fromCharCodes(bytes), contains('-' * 32));
  });

  test('buildReceipt has no GS v 0 when logo is null', () async {
    final bytes = await ReceiptBuilder.buildReceipt(_txn, _profile());

    expect(_containsSub(bytes, gsV0), isFalse);
    expect(String.fromCharCodes(bytes), contains('TOTAL'));
  });

  test('missing logo file still produces receipt without error', () async {
    final bytes = await ReceiptBuilder.buildReceipt(
        _txn, _profile(useLogo: true, logoPath: 'logo/missing.jpg'));

    expect(_containsSub(bytes, gsV0), isFalse);
    expect(String.fromCharCodes(bytes), contains('TOTAL'));
  });

  test('buildReceipt prints store name bold ukuran normal, once', () async {
    final bytes = await ReceiptBuilder.buildReceipt(_txn, _profile());
    final text = String.fromCharCodes(bytes);
    final name = _profile().name.toUpperCase();
    // 58mm = 32 kolom; "WARUNG BUDI" 11 huruf → sisa 21, ganjil → 11 spasi depan.
    expect(text, contains('\x1B\x45\x01${' ' * 11}$name\n\x1B\x45\x00'));
    expect(text, isNot(contains('\x1D\x21')), reason: 'ukuran normal');
    expect(text, isNot(contains('\x1B\x61\x01')),
        reason: 'jangan andalkan ESC a: printer murah mengabaikannya');
    expect(name.allMatches(text).length, 1);
  });

  group('fitLogo', () {
    test('logo besar 58mm: tinggi maks 112, kanvas selebar kertas, di tengah', () {
      final src = img.Image(1000, 1000)..fill(img.getColor(0, 0, 0));
      final out = ReceiptBuilder.fitLogo(src, 58);
      expect(out.width, 384);
      expect(out.height, 112 + ReceiptBuilder.logoGapDots);
      // baris jarak di bawah logo putih
      expect(img.getRed(out.getPixel(192, out.height - 1)), 255);
      // kiri & kanan putih, tengah hitam
      expect(img.getRed(out.getPixel(0, 40)), 255);
      expect(img.getRed(out.getPixel(383, 40)), 255);
      expect(img.getRed(out.getPixel(192, 40)), 0);
      expect(img.getRed(out.getPixel(136, 40)), 0); // (384-112)/2 = 136
      expect(img.getRed(out.getPixel(135, 40)), 255);
    });

    test('pinggiran putih logo dipotong: hitam mulai di baris 0', () {
      // 200x200 putih, kotak hitam 20x20 di tengah (pinggiran putih tebal).
      final src = img.Image(200, 200)..fill(img.getColor(255, 255, 255));
      img.fillRect(src, 90, 90, 109, 109, img.getColor(0, 0, 0));
      final out = ReceiptBuilder.fitLogo(src, 58);
      expect(out.height, 20 + ReceiptBuilder.logoGapDots);
      expect(img.getRed(out.getPixel(192, 0)), 0);
    });

    test('logo putih semua tidak error', () {
      final src = img.Image(50, 50)..fill(img.getColor(255, 255, 255));
      expect(ReceiptBuilder.fitLogo(src, 58).width, 384);
    });

    test('logo lebar 80mm: dibatasi 40% lebar kertas', () {
      final src = img.Image(2000, 100)..fill(img.getColor(0, 0, 0));
      final out = ReceiptBuilder.fitLogo(src, 80);
      expect(out.width, 576);
      expect(out.height, lessThanOrEqualTo(112 + ReceiptBuilder.logoGapDots));
      expect(img.getRed(out.getPixel(0, 0)), 255);
      expect(img.getRed(out.getPixel(288, 0)), 0);
    });
  });
}
