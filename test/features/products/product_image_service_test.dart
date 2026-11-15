import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kasir_resto/features/products/product_image_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  late Directory docs;
  late ProductImageService service;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('kasir_product_image_test_');
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
    service = ProductImageService();
  });

  tearDown(() async {
    if (await docs.exists()) await docs.delete(recursive: true);
  });

  Future<XFile> sourceJpg(List<int> bytes) async {
    final f = File(p.join(docs.path, 'source.jpg'));
    await f.writeAsBytes(bytes);
    return XFile(f.path);
  }

  File storedFile(String productId) =>
      File(p.join(docs.path, 'images', 'products', '$productId.jpg'));

  test('saveLocal copies into images/products and returns relative path',
      () async {
    final src = await sourceJpg([1, 2, 3, 4]);

    final path = await service.saveLocal('p1', src);

    expect(path, p.join('products', 'p1.jpg'));
    expect(p.isAbsolute(path), isFalse);
    expect(storedFile('p1').existsSync(), isTrue);
    expect(await storedFile('p1').readAsBytes(), [1, 2, 3, 4]);
  });

  test('saveLocal overwrites the previous photo of the same product', () async {
    await service.saveLocal('p1', await sourceJpg([1]));
    await service.saveLocal('p1', await sourceJpg([9, 9]));

    expect(await storedFile('p1').readAsBytes(), [9, 9]);
  });

  test('deleteLocal removes the stored photo', () async {
    await service.saveLocal('p1', await sourceJpg([1]));
    await service.saveLocal('p2', await sourceJpg([2]));

    await service.deleteLocal('p1');

    expect(storedFile('p1').existsSync(), isFalse);
    expect(storedFile('p2').existsSync(), isTrue);
  });

  test('deleteLocal is safe when there is no photo', () async {
    await expectLater(service.deleteLocal('missing'), completes);
  });

  test('resolvePath points at the saved file under images/', () async {
    final relative = await service.saveLocal('p2', await sourceJpg([5]));

    final absolute = await ProductImageService.resolvePath(relative);

    expect(absolute, p.join(docs.path, 'images', 'products', 'p2.jpg'));
    expect(File(absolute).existsSync(), isTrue);
  });

  test('resolvePath leaves legacy absolute paths untouched', () async {
    final absolute = p.join(docs.path, 'images', 'products', 'old.jpg');

    expect(await ProductImageService.resolvePath(absolute), absolute);
  });
}
