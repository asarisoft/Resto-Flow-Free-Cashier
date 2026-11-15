import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ProductImageService {
  Future<XFile?> pickImage() async {
    return ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 70,
    );
  }

  Future<String> saveLocal(String productId, XFile file) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'images', 'products'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final dest = File(p.join(dir.path, '$productId.jpg'));
    await File(file.path).copy(dest.path);
    return dest.path;
  }

  Future<void> deleteLocal(String productId) async {
    final docs = await getApplicationDocumentsDirectory();
    final f = File(p.join(docs.path, 'images', 'products', '$productId.jpg'));
    if (await f.exists()) await f.delete();
  }
}
