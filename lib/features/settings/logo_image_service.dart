import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Simpan/ambil logo resto di folder yang sama dengan foto produk
/// (`<appDocuments>/images/`), sehingga ikut terbawa backup zip.
class LogoImageService {
  static const imagesDirName = 'images';
  static const logoDirName = 'logo';
  static const logoFileName = 'logo.jpg';

  Future<XFile?> pickImage() async {
    return ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 384,
      maxHeight: 384,
      imageQuality: 85,
    );
  }

  /// Copies [file] to `<appDocuments>/images/logo/logo.jpg` and returns the
  /// relative path `logo/logo.jpg` stored in the DB (sama pola foto produk).
  Future<String> saveLocal(XFile file) async {
    final dir = await _logoDir();
    final dest = File(p.join(dir.path, logoFileName));
    await File(file.path).copy(dest.path);
    return p.join(logoDirName, logoFileName);
  }

  Future<void> deleteLocal() async {
    final f = File(p.join((await _logoDir()).path, logoFileName));
    if (await f.exists()) await f.delete();
  }

  /// Resolves a DB `logoPath` to an absolute file path.
  ///
  /// Absolute paths (legacy rows written before the relative-path fix) are
  /// returned untouched.
  static Future<String> resolvePath(String logoPath) async {
    if (p.isAbsolute(logoPath)) return logoPath;
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, imagesDirName, logoPath);
  }

  /// Flattens [src] onto a white background.
  ///
  /// Transparent pixels (black RGB with alpha 0, common in PNG logos) rasterize
  /// as black boxes on the receipt; compositing over white makes them print as
  /// white instead. Opaque pixels keep their color.
  static img.Image flattenToWhite(img.Image src) {
    final white = img.Image(src.width, src.height);
    img.fill(white, img.getColor(255, 255, 255, 255));
    return img.drawImage(white, src);
  }

  Future<Directory> _logoDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, imagesDirName, logoDirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
