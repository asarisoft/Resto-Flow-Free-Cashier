import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kasir_resto/features/settings/logo_image_service.dart';

void main() {
  test('flattenToWhite turns transparent pixels white, keeps opaque color',
      () {
    final src = img.Image(2, 1);
    src.setPixel(0, 0, img.getColor(0, 0, 0, 0)); // transparan "hitam"
    src.setPixel(1, 0, img.getColor(255, 0, 0, 255)); // merah pekat

    final out = LogoImageService.flattenToWhite(src);

    expect(out.getPixel(0, 0), img.getColor(255, 255, 255, 255));
    expect(out.getPixel(1, 0), img.getColor(255, 0, 0, 255));
  });

  test('flattenToWhite flattens a decoded transparent PNG to all white', () {
    // PNG transparan penuh (tiap piksel hitam + alpha 0) — umum pada logo.
    final src = img.Image(3, 3);
    final decoded = img.decodeImage(img.encodePng(src))!;

    final out = LogoImageService.flattenToWhite(decoded);

    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        expect(out.getPixel(x, y), img.getColor(255, 255, 255, 255),
            reason: 'piksel transparan harus jadi putih, bukan hitam');
      }
    }
  });
}
