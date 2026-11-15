import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/products_dao.dart';
import 'package:kasir_resto/core/services/database.dart' show AppDatabase;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/features/auth/login_page.dart';
import 'package:kasir_resto/features/expenses/expense_list_page.dart';
import 'package:kasir_resto/core/services/daos/profile_dao.dart';
import 'package:kasir_resto/models/resto_profile.dart';
import 'package:kasir_resto/features/home/home_shell.dart';
import 'package:kasir_resto/features/auth/auth_controller.dart' show currentUserProvider;
import 'package:kasir_resto/models/app_user.dart';
import 'package:kasir_resto/features/pos/pos_page.dart';
import 'package:kasir_resto/features/reports/report_page.dart';
import 'package:kasir_resto/features/users/user_list_page.dart';
import 'package:kasir_resto/core/services/daos/expenses_dao.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/core/services/daos/users_dao.dart';
import 'package:kasir_resto/models/expense.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/main.dart' show clampTextScale;
import 'package:kasir_resto/models/product.dart';
import 'package:kasir_resto/models/transaction_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

const wideSizes = <String, Size>{
  'tablet 1280x800': Size(1280, 800),
  'tablet 1920x1200': Size(1920, 1200),
  'landscape 800x360': Size(800, 360),
};

const sizes = <String, Size>{
  'phone 375x667': Size(375, 667),
  'landscape 800x360': Size(800, 360),
  'tablet 1024x768': Size(1024, 768),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTest();
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Size size, Widget page, {double textScale = 1.0}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() async {
      // Lepas pohon widget & biarkan timer stream drift selesai.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light, builder: clampTextScale, home: page),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  for (final e in sizes.entries) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('LoginPage has no overflow on ${e.key} @ text ${scale}x', (tester) async {
        await pump(tester, e.value, const LoginPage(), textScale: scale);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ExpenseListPage has no overflow on ${e.key} @ text ${scale}x', (tester) async {
        final now = DateTime.now();
        await ExpensesDao(db).add(Expense(
            amount: 125000, category: 'Bahan baku dapur', note: 'Beras 25kg dan minyak goreng untuk satu minggu', date: now, createdAt: now));
        await pump(tester, e.value, const ExpenseListPage(), textScale: scale);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ReportPage has no overflow on ${e.key} @ text ${scale}x', (tester) async {
        await SalesDao(db).save(Transaction(
          number: 1,
          items: const [TransactionItem(productId: 'p', name: 'Nasi Goreng', price: 30000, hpp: 9000)],
          subtotal: 30000, total: 30000, paid: 50000, change: 20000, profit: 21000,
          createdAt: DateTime.now(),
        ));
        await pump(tester, e.value, const ReportPage(), textScale: scale);
        expect(tester.takeException(), isNull);
      });

      testWidgets('UserListPage has no overflow on ${e.key} @ text ${scale}x', (tester) async {
        await UsersDao(db).seedDefaultOwnerIfEmpty();
        await pump(tester, e.value, const UserListPage(), textScale: scale);
        expect(tester.takeException(), isNull);
      });

      testWidgets('PosPage has no overflow on ${e.key} @ text ${scale}x', (tester) async {
        final dao = ProductsDao(db);
        final now = DateTime(2026, 11, 15);
        await dao.add(Product(name: 'Nasi Goreng Spesial Pedas', price: 25000, hpp: 9000, createdAt: now, updatedAt: now));
        await dao.add(Product(name: 'Es Teh', price: 5000, ready: false, createdAt: now, updatedAt: now));
        await pump(tester, e.value, const PosPage(), textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  }

  group('wide layout', () {
    for (final e in wideSizes.entries) {
      testWidgets('HomeShell sidebar has no overflow on ${e.key}', (tester) async {
        tester.view.physicalSize = e.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await ProfileDao(db).save(RestoProfile(name: 'Warung Budi', createdAt: DateTime(2026)));
        await tester.pumpWidget(ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            currentUserProvider.overrideWith((ref) async =>
                AppUser(id: 'o1', username: 'admin', role: 'owner', active: true)),
          ],
          child: MaterialApp(theme: AppTheme.light, builder: clampTextScale, home: const HomeShell()),
        ));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(find.text('Resto Flow Free'), findsOneWidget, reason: 'sidebar must be visible (not onboarding)');
        expect(tester.takeException(), isNull);
      });
    }

    for (final w in [1280.0, 1920.0]) {
      testWidgets('POS cart panel stays 300-340dp wide at ${w.toInt()}dp', (tester) async {
        await pump(tester, Size(w, 800), const PosPage());
        final width = tester.getSize(find.byKey(const Key('cart_panel'))).width;
        expect(width, inInclusiveRange(300, 340));
      });
    }
  });
}
