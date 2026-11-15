import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ProductImageService {
  static const imagesDirName = 'images';
  static const productsDirName = 'products';

  Future<XFile?> pickImage() async {
    return ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 70,
    );
  }

  /// Copies [file] to `<appDocuments>/images/products/<productId>.jpg` and
  /// returns the relative path `products/<productId>.jpg` stored in the DB.
  Future<String> saveLocal(String productId, XFile file) async {
    final dir = await _productsDir();
    final dest = File(p.join(dir.path, '$productId.jpg'));
    await File(file.path).copy(dest.path);
    return p.join(productsDirName, '$productId.jpg');
  }

  Future<void> deleteLocal(String productId) async {
    final f = File(p.join((await _productsDir()).path, '$productId.jpg'));
    if (await f.exists()) await f.delete();
  }

  /// Resolves a DB `imagePath` to an absolute file path.
  ///
  /// Absolute paths (legacy rows written before the relative-path fix) are
  /// returned untouched.
  static Future<String> resolvePath(String imagePath) async {
    if (p.isAbsolute(imagePath)) return imagePath;
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, imagesDirName, imagePath);
  }

  Future<Directory> _productsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, imagesDirName, productsDirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
