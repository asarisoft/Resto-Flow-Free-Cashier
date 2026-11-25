import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/profile_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/features/auth/auth_controller.dart';
import 'package:kasir_resto/core/theme/app_colors.dart';
import 'package:kasir_resto/features/support/support_page.dart';
import 'package:kasir_resto/features/categories/category_page.dart';
import 'package:kasir_resto/features/settings/settings_page.dart';
import 'package:kasir_resto/models/app_user.dart';
import 'package:kasir_resto/models/resto_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTest();
    await ProfileDao(db)
        .save(RestoProfile(name: 'Warung A', createdAt: DateTime.now()));
  });

  Future<void> pump(WidgetTester tester, String role,
      {Size size = const Size(800, 1600)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await db.close();
      tester.view.reset();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentUserProvider.overrideWith((ref) async =>
            AppUser(id: 'u1', username: 'u', role: role, active: true)),
      ],
      child: const MaterialApp(home: SettingsPage()),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('Owner: tile Kategori tampil & membuka CategoryPage', (tester) async {
    await pump(tester, 'owner');
    final tile = find.text('Kategori');
    await tester.scrollUntilVisible(tile, 200);
    expect(find.text('Ubah nama & hapus kategori produk/pengeluaran'), findsOneWidget);
    await tester.tap(tile);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(CategoryPage), findsOneWidget);
  });

  testWidgets('List pengaturan memakai klip (tidak menimpa header)', (tester) async {
    for (final size in const [Size(800, 1600), Size(1200, 800), Size(400, 800)]) {
      await pump(tester, 'owner', size: size);
      final list = tester.widget<ListView>(find.byType(ListView).first);
      expect(list.clipBehavior, isNot(Clip.none));
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Kasir: tile Kategori tidak tampil', (tester) async {
    await pump(tester, 'kasir');
    expect(find.text('Kategori'), findsNothing);
  });

  double lum(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
  }

  testWidgets('HP: tile Dukung di atas Profil Resto, kontras ok, buka SupportPage',
      (tester) async {
    await pump(tester, 'owner', size: const Size(360, 800));
    final tile = find.text('Dukung Developer');
    expect(tile, findsOneWidget);
    expect(find.text('Follow, request fitur & pesan aplikasi'), findsOneWidget);
    expect(tester.getTopLeft(tile).dy,
        lessThan(tester.getTopLeft(find.text('Profil Resto')).dy));
    expect(lum(AppColors.textPrimary, AppColors.lilac), greaterThanOrEqualTo(4.5));
    expect(lum(AppColors.textSecondary, AppColors.lilac), greaterThanOrEqualTo(4.5));

    await tester.tap(tile);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(SupportPage), findsOneWidget);
  });
}
