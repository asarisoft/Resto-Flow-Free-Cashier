import 'package:flutter_test/flutter_test.dart';
import 'package:image_cropper_platform_interface/image_cropper_platform_interface.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:kasir_resto/features/settings/logo_image_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePicker extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  XFile? result;
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async =>
      result;
}

class _FakeCropper extends ImageCropperPlatform with MockPlatformInterfaceMixin {
  CroppedFile? result;
  String? croppedFrom;
  int? maxWidth;
  @override
  Future<CroppedFile?> cropImage({
    required String sourcePath,
    int? maxWidth,
    int? maxHeight,
    CropAspectRatio? aspectRatio,
    ImageCompressFormat compressFormat = ImageCompressFormat.jpg,
    int compressQuality = 90,
    List<PlatformUiSettings>? uiSettings,
  }) async {
    croppedFrom = sourcePath;
    this.maxWidth = maxWidth;
    return result;
  }
}

void main() {
  late _FakePicker picker;
  late _FakeCropper cropper;

  setUp(() {
    picker = _FakePicker();
    cropper = _FakeCropper();
    ImagePickerPlatform.instance = picker;
    ImageCropperPlatform.instance = cropper;
  });

  test('pilih foto lalu crop → pakai file hasil crop (maks 384)', () async {
    picker.result = XFile('/tmp/foto.jpg');
    cropper.result = CroppedFile('/tmp/crop.jpg');

    final file = await LogoImageService().pickImage();

    expect(cropper.croppedFrom, '/tmp/foto.jpg');
    expect(cropper.maxWidth, 384);
    expect(file?.path, '/tmp/crop.jpg');
  });

  test('batal crop → null, logo lama tidak diganti', () async {
    picker.result = XFile('/tmp/foto.jpg');
    cropper.result = null;

    expect(await LogoImageService().pickImage(), isNull);
  });

  test('batal pilih foto → null, layar crop tidak dibuka', () async {
    picker.result = null;

    expect(await LogoImageService().pickImage(), isNull);
    expect(cropper.croppedFrom, isNull);
  });
}
