import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart';
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/features/backup/backup_reminder.dart';
import 'package:kasir_resto/features/backup/backup_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

class _FakePicker extends FilePickerPlatform {
  _FakePicker(this.result);
  final Uri? result;
  Uint8List? savedBytes;
  String? savedName;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    savedBytes = bytes;
    savedName = fileName;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late Directory docs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Kasir Ceria',
      packageName: 'id.asdev.kasirceria',
      version: '1.0.0',
      buildNumber: '2',
      buildSignature: '',
    );
    docs = await Directory.systemTemp.createTemp('kasir_save_');
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
    db = AppDatabase.forTest();
    await db.into(db.products).insert(ProductsCompanion.insert(
        id: 'p1',
        name: 'Nasi Goreng',
        price: 15000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now()));
  });
  tearDown(() async {
    await db.close();
    await docs.delete(recursive: true);
  });

  Future<void> tapSave(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => runBackupToDevice(ref, context),
              child: const Text('simpan'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('simpan'));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
  }

  testWidgets('simpan sukses: zip berisi data, backup tercatat', (tester) async {
    final picker = _FakePicker(Uri.parse('content://downloads/backup.zip'));
    FilePickerPlatform.instance = picker;
    await tapSave(tester);

    expect(find.text('Backup disimpan'), findsOneWidget);
    expect(picker.savedName, endsWith('.zip'));
    final names = ZipDecoder().decodeBytes(picker.savedBytes!).map((e) => e.name);
    expect(names, containsAll(['database.db', 'manifest.json']));
    expect(await BackupService.lastBackupTime(), isNotNull);
  });

  testWidgets('dialog simpan dibatalkan: tidak dicatat sebagai backup',
      (tester) async {
    FilePickerPlatform.instance = _FakePicker(null);
    await tapSave(tester);

    expect(find.text('Simpan dibatalkan'), findsOneWidget);
    expect(await BackupService.lastBackupTime(), isNull);
  });

  test('label versi: app + build + skema DB', () async {
    final c = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    expect(await c.read(appVersionLabelProvider.future),
        'Kasir Ceria v1.0.0 (2) · skema DB 1');
  });
}
