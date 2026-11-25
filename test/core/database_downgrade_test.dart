import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart';
import 'package:kasir_resto/features/auth/auth_controller.dart';
import 'package:kasir_resto/features/auth/register_page.dart';
import 'package:path/path.dart' as p;

void main() {
  test('DB user_version=99 ditolak & file tidak diubah', () async {
    final temp = await Directory.systemTemp.createTemp('kasir_downgrade_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File(p.join(temp.path, 'kasir_resto.sqlite'));

    final seed = AppDatabase.forFile(file);
    await seed.customStatement('PRAGMA user_version = 99');
    await seed.close();
    final before = await file.readAsBytes();

    final db = AppDatabase.forFile(file);
    await expectLater(
      db.select(db.users).get(),
      throwsA(predicate(isDatabaseTooNew)),
    );
    await db.close().catchError((_) {});
    expect(await file.readAsBytes(), before);
  });

  testWidgets('layar "Update aplikasi dulu" muncul saat DB terlalu baru',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        hasAnyUserProvider
            .overrideWith((ref) => throw const DatabaseTooNewException(99, 1)),
      ],
      child: const MaterialApp(home: AuthGate()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Update aplikasi dulu'), findsOneWidget);
    expect(find.text('Masuk'), findsNothing);
  });
}
