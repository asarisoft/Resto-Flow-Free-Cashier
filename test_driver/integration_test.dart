import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Simpan screenshot ke `$SCREENSHOT_DIR/<nama>.png` (default `screnshoot/`).
/// Dipakai `screenshots.sh`.
Future<void> main() => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final dir = Directory(Platform.environment['SCREENSHOT_DIR'] ?? 'screnshoot')
          ..createSync(recursive: true);
        File('${dir.path}/$name.png').writeAsBytesSync(bytes);
        return true;
      },
    );
