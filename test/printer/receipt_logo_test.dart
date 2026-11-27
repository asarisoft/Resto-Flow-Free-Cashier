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
    expect(_containsSub(bytes, [0x1B, 0x4A, 24]), isTrue,
        reason: 'harus ada jarak (ESC J) antara logo dan nama toko');
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

  test('buildReceipt prints store name double-size & bold, once', () async {
    final bytes = await ReceiptBuilder.buildReceipt(_txn, _profile());
    final text = String.fromCharCodes(bytes);
    final name = _profile().name.toUpperCase();
    expect(text, contains('\x1D\x21\x11\x1B\x45\x01$name\n\x1D\x21\x00'));
    expect(name.allMatches(text).length, 1);
  });

  group('fitLogo', () {
    test('logo besar 58mm: tinggi maks 80, kanvas selebar kertas, di tengah', () {
      final src = img.Image(1000, 1000)..fill(img.getColor(0, 0, 0));
      final out = ReceiptBuilder.fitLogo(src, 58);
      expect(out.width, 384);
      expect(out.height, 80);
      // kiri & kanan putih, tengah hitam
      expect(img.getRed(out.getPixel(0, 40)), 255);
      expect(img.getRed(out.getPixel(383, 40)), 255);
      expect(img.getRed(out.getPixel(192, 40)), 0);
      expect(img.getRed(out.getPixel(152, 40)), 0); // (384-80)/2 = 152
      expect(img.getRed(out.getPixel(151, 40)), 255);
    });

    test('logo lebar 80mm: dibatasi 40% lebar kertas', () {
      final src = img.Image(2000, 100)..fill(img.getColor(0, 0, 0));
      final out = ReceiptBuilder.fitLogo(src, 80);
      expect(out.width, 576);
      expect(out.height, lessThanOrEqualTo(80));
      expect(img.getRed(out.getPixel(0, 0)), 255);
      expect(img.getRed(out.getPixel(288, 0)), 0);
    });
  });
}
